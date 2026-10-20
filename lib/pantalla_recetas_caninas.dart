import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pantalla_detalle_receta.dart';
import 'pantalla_chef.dart';
import 'pantalla_agregar_receta.dart';
import 'servicio_recetas.dart';
import 'servicio_admin.dart';
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
          .order('id_receta', ascending: false);

      if (!mounted) return;
      final lista = List<Map<String, dynamic>>.from(respuesta)
          .where((r) => ServicioRecetas.esRecetaCanina(r))
          .toList();

      setState(() {
        recetasCaninas = lista;
        recetasFiltradas = recetasCaninas;
        cargando = false;
      });
      _filtrar();
    } catch (e) {
      debugPrint('Error al cargar recetas caninas: $e');
      if (mounted) setState(() => cargando = false);
    }
  }

  void _filtrar() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      recetasFiltradas = recetasCaninas.where((r) {
        final titulo = r['titulo']?.toString().toLowerCase() ?? '';
        final desc = r['descripcion']?.toString().toLowerCase() ?? '';
        return query.isEmpty || titulo.contains(query) || desc.contains(query);
      }).toList();
    });
  }

  Future<void> _confirmarEliminarReceta(int idReceta, String titulo) async {
    final bool esAdmin = ServicioAdmin.esAdmin();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar Receta Canina'),
          ],
        ),
        content: Text(
          esAdmin
              ? '¿Eliminar definitivamente "$titulo"? Como administrador, se borrará del recetario canino para todos los usuarios.'
              : '¿Estás seguro de eliminar tu receta "$titulo"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await ServicioRecetas.eliminarReceta(idReceta);
      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Receta canina "$titulo" eliminada 🐾'),
            backgroundColor: Colors.brown[800],
          ),
        );
        cargarRecetasCaninas();
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo eliminar la receta canina. Verifica permisos en Supabase o conexión.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarOpcionesCreacion() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 15),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets, color: Colors.brown, size: 26),
                    SizedBox(width: 10),
                    Text(
                      'Nueva Receta Canina 🐾',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige cómo prefieres crear tu receta o premio para consentir a tu lomito:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.brown[50],
                    radius: 24,
                    child: const Icon(Icons.auto_awesome, color: Colors.brown),
                  ),
                  title: const Text(
                    'Chef Perruno con IA 🐶✨',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Genera premios balanceados y seguros según los ingredientes que tengas en casa',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const PantallaChef(modoPerrunoInicial: true),
                      ),
                    ).then((_) => cargarRecetasCaninas());
                  },
                ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange[50],
                    radius: 24,
                    child: const Icon(Icons.edit_note, color: Colors.orange),
                  ),
                  title: const Text(
                    'Escribir Receta Manual ✍️',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Escribe tu receta familiar y compártela con toda la comunidad de Jitomate y Cebolla',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PantallaAgregarReceta(
                          tipoComidaInicial: 'Snack Canino',
                        ),
                      ),
                    ).then((_) => cargarRecetasCaninas());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _construirBadgeOrigen(Map<String, dynamic> receta) {
    if (ServicioRecetas.esMiReceta(receta)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person, size: 12, color: Colors.amber.shade900),
            const SizedBox(width: 4),
            Text(
              'Creada por ti 🐾',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade900,
              ),
            ),
          ],
        ),
      );
    } else if (ServicioRecetas.esOficial(receta)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 12, color: Colors.orange.shade900),
            const SizedBox(width: 4),
            Text(
              'Oficial 🌟',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public, size: 12, color: Colors.teal.shade800),
            const SizedBox(width: 4),
            Text(
              'Comunidad 🌎',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade800,
              ),
            ),
          ],
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
        leadingWidth: 56,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28, color: Colors.white),
            tooltip: 'Menú principal',
            splashRadius: 26,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
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
        backgroundColor: const Color(0xFF1E2022),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Crear receta canina',
            onPressed: _mostrarOpcionesCreacion,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarOpcionesCreacion,
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.pets),
        label: const Text(
          'Nueva Receta 🐾',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                : RefreshIndicator(
                    color: Colors.brown[700],
                    onRefresh: cargarRecetasCaninas,
                    child: recetasFiltradas.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.5,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.pets,
                                        size: 80,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 15),
                                      const Text(
                                        'No hay recetas caninas disponibles aún',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.brown[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                        ),
                                        icon: const Icon(Icons.add),
                                        label: const Text(
                                          'Crear la primera receta 🐶',
                                        ),
                                        onPressed: _mostrarOpcionesCreacion,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(
                              left: 15,
                              right: 15,
                              top: 15,
                              bottom: 85,
                            ),
                            itemCount: recetasFiltradas.length,
                    itemBuilder: (context, index) {
                      final receta = recetasFiltradas[index];
                      final id = receta['id_receta'] as int;
                      final titulo = receta['titulo'] ?? 'Premio Perruno';
                      final descripcion = receta['descripcion'] ?? '';
                      final imagenUrl = ServicioRecetas.obtenerImagenOptimizada(
                        idReceta: id,
                        titulo: titulo,
                        rawUrl: receta['imagen_url']?.toString(),
                      );
                      final puedeEliminar = ServicioRecetas.puedeModificar(
                        receta,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: Colors.brown[100],
                            radius: 26,
                            backgroundImage:
                                (imagenUrl != null && imagenUrl.isNotEmpty)
                                ? NetworkImage(imagenUrl)
                                : null,
                            child: (imagenUrl == null || imagenUrl.isEmpty)
                                ? const Icon(
                                    Icons.pets,
                                    color: Colors.brown,
                                    size: 28,
                                  )
                                : null,
                          ),
                          title: Text(
                            titulo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.brown[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Apto para perros 🐶',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.brown,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _construirBadgeOrigen(receta),
                              ],
                            ),
                          ),
                          trailing: puedeEliminar
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: ServicioAdmin.esAdmin()
                                      ? 'Eliminar receta (Administrador)'
                                      : 'Eliminar mi receta',
                                  onPressed: () =>
                                      _confirmarEliminarReceta(id, titulo),
                                )
                              : null,
                          onTap: () async {
                            final eliminada = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PantallaDetalleReceta(
                                  idReceta: id,
                                  titulo: titulo,
                                  descripcion: descripcion,
                                  imagenUrl: imagenUrl,
                                ),
                              ),
                            );
                            if (eliminada == true) {
                              cargarRecetasCaninas();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
