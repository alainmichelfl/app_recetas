import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pantalla_recetas.dart';
import 'pantalla_planeador.dart';
import 'pantalla_despensa.dart';
import 'pantalla_carrito.dart';
import 'pantalla_cotizador.dart';
import 'pantalla_chef.dart';
import 'pantalla_recetas_caninas.dart';
import 'pantalla_salud.dart';
import 'pantalla_finanzas.dart';
import 'pantalla_preferencias.dart';
import 'pantalla_login.dart';

/// Menú lateral (Drawer) reutilizable presente en todas las páginas de la app.
/// Proporciona acceso rápido y consistente a todas las secciones principales.
class MenuLateral extends StatelessWidget {
  final String? rutaActual;

  const MenuLateral({
    super.key,
    this.rutaActual,
  });

  void _navegar(BuildContext context, String rutaDestino, Widget Function() constructorPantalla) {
    Navigator.pop(context); // Cierra el Drawer

    // Si ya estamos en la misma ruta, no recargar
    if (rutaActual == rutaDestino) return;

    if (rutaDestino == 'recetas') {
      // Si volvemos al catálogo principal, limpiar el stack para mantenerlo en la base
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => constructorPantalla()),
        (route) => false,
      );
    } else {
      // Reemplazar la ruta secundaria actual para evitar acumulación infinita de pantallas
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => constructorPantalla()),
        (route) => route.isFirst,
      );
    }
  }

  Widget _construirItem({
    required BuildContext context,
    required String ruta,
    required String titulo,
    required IconData icono,
    required Color colorIcono,
    required Widget Function() pantalla,
    String? badge,
  }) {
    final bool esActiva = rutaActual == ruta;

    return ListTile(
      dense: true,
      selected: esActiva,
      selectedTileColor: colorIcono.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: esActiva ? colorIcono : colorIcono.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icono,
          color: esActiva ? Colors.white : colorIcono,
          size: 20,
        ),
      ),
      title: Text(
        titulo,
        style: TextStyle(
          fontWeight: esActiva ? FontWeight.bold : FontWeight.w600,
          color: esActiva ? colorIcono : Colors.black87,
          fontSize: 15,
        ),
      ),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorIcono.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorIcono,
                ),
              ),
            )
          : (esActiva
              ? Icon(Icons.circle, size: 8, color: colorIcono)
              : null),
      onTap: () => _navegar(context, ruta, pantalla),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final String emailUsuario = user?.email ?? 'Chef Invitado';

    return Drawer(
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Cabecera elegante con degradado de marca
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD32F2F),
                    Colors.orange.shade800,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          color: Color(0xFFD32F2F),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jitomate y Cebolla',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Tu Asistente Culinario',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, color: Colors.white70, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            emailUsuario,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lista de Secciones
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      'PRINCIPAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _construirItem(
                    context: context,
                    ruta: 'recetas',
                    titulo: 'Mis Recetas',
                    icono: Icons.menu_book,
                    colorIcono: Colors.orange.shade800,
                    pantalla: () => const PantallaRecetas(),
                  ),
                  _construirItem(
                    context: context,
                    ruta: 'planeador',
                    titulo: 'Mi Planeador',
                    icono: Icons.calendar_month,
                    colorIcono: Colors.teal,
                    pantalla: () => const PantallaPlaneador(),
                  ),
                  _construirItem(
                    context: context,
                    ruta: 'despensa',
                    titulo: 'Mi Despensa',
                    icono: Icons.kitchen,
                    colorIcono: Colors.blue.shade700,
                    pantalla: () => const PantallaDespensa(),
                  ),
                  _construirItem(
                    context: context,
                    ruta: 'carrito',
                    titulo: 'Lista de Compras',
                    icono: Icons.shopping_cart,
                    colorIcono: Colors.green.shade700,
                    pantalla: () => const PantallaCarrito(),
                  ),
                  _construirItem(
                    context: context,
                    ruta: 'cotizador',
                    titulo: 'Cotizador',
                    icono: Icons.calculate,
                    colorIcono: Colors.deepPurple,
                    pantalla: () => const PantallaCotizador(),
                  ),
                  _construirItem(
                    context: context,
                    ruta: 'chef',
                    titulo: 'Chef IA',
                    icono: Icons.auto_awesome,
                    colorIcono: Colors.amber.shade800,
                    pantalla: () => const PantallaChef(),
                  ),
                  _construirItem(
                    context: context,
                    ruta: 'caninas',
                    titulo: 'Recetas Caninas',
                    icono: Icons.pets,
                    colorIcono: Colors.brown,
                    pantalla: () => const PantallaRecetasCaninas(),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Divider(height: 1),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      'BIENESTAR Y AJUSTES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _construirItem(
                    context: context,
                    ruta: 'salud',
                    titulo: 'Mi Salud',
                    icono: Icons.favorite,
                    colorIcono: Colors.pinkAccent,
                    pantalla: () => const PantallaSalud(),
                  ),
                  _construirItem(
                    context: context,
                    ruta: 'finanzas',
                    titulo: 'Mis Finanzas',
                    icono: Icons.account_balance_wallet,
                    colorIcono: Colors.indigo,
                    pantalla: () => const PantallaFinanzas(),
                  ),
                  _construirItem(
                    context: context,
                    ruta: 'preferencias',
                    titulo: 'Mis Preferencias',
                    icono: Icons.settings,
                    colorIcono: Colors.blueGrey,
                    pantalla: () => const PantallaPreferencias(),
                  ),
                ],
              ),
            ),

            // Pie con Cerrar Sesión
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.exit_to_app, color: Colors.red, size: 20),
              ),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PantallaLogin(),
                    ),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
