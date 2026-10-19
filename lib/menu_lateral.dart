import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pantalla_recetas.dart';
import 'servicio_recetas.dart';
import 'pantalla_planeador.dart';
import 'pantalla_calendario.dart';
import 'pantalla_despensa.dart';
import 'pantalla_carrito.dart';
import 'pantalla_cotizador.dart';
import 'pantalla_chef.dart';
import 'pantalla_sommelier.dart';
import 'pantalla_recetas_caninas.dart';
import 'pantalla_salud.dart';
import 'pantalla_finanzas.dart';
import 'pantalla_preferencias.dart';
import 'pantalla_login.dart';
import 'servicio_hogar.dart';
import 'dialogo_manifiesto_bienvenida.dart';
import 'dialogo_contacto_soporte.dart';
import 'dialogo_busqueda_spotlight.dart';
import 'dialogo_onboarding_bienvenida.dart';
import 'servicio_recordatorios.dart';

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

    if (rutaDestino == 'recetas' || rutaDestino == 'recetas_mias') {
      // Si volvemos al catálogo principal o mis creaciones, limpiar el stack para mantenerlo en la base
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

  Widget _construirSubItem({
    required BuildContext context,
    required String ruta,
    required String titulo,
    required IconData icono,
    required Color colorIcono,
    Widget Function()? pantalla,
    VoidCallback? alPresionar,
    String? subtitulo,
    String? badge,
  }) {
    final bool esActiva = rutaActual == ruta;

    return ListTile(
      dense: true,
      selected: esActiva,
      selectedTileColor: colorIcono.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      leading: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: esActiva ? colorIcono : colorIcono.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icono,
          color: esActiva ? Colors.white : colorIcono,
          size: 16,
        ),
      ),
      title: Text(
        titulo,
        style: TextStyle(
          fontWeight: esActiva ? FontWeight.bold : FontWeight.w600,
          color: esActiva ? colorIcono : Colors.black87,
          fontSize: 13.5,
        ),
      ),
      subtitle: subtitulo != null
          ? Text(
              subtitulo,
              style: TextStyle(
                fontSize: 11,
                color: esActiva ? colorIcono.withValues(alpha: 0.85) : Colors.grey.shade600,
              ),
            )
          : null,
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorIcono.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colorIcono,
                ),
              ),
            )
          : (esActiva
              ? Icon(Icons.circle, size: 7, color: colorIcono)
              : null),
      onTap: () {
        if (alPresionar != null) {
          alPresionar();
        } else if (pantalla != null) {
          _navegar(context, ruta, pantalla);
        }
      },
    );
  }

  Widget _construirMenuRecetasConSubmenu(BuildContext context) {
    final bool esGrupoActivo = rutaActual == 'recetas' ||
        rutaActual == 'recetas_mias' ||
        rutaActual == 'caninas';

    const Color colorGrupo = Color(0xFFC62828); // Rojo Jitomate Gourmet

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: esGrupoActivo ? colorGrupo.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          initiallyExpanded: esGrupoActivo,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          childrenPadding: const EdgeInsets.only(left: 14, right: 8, bottom: 6),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: esGrupoActivo ? colorGrupo : colorGrupo.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: esGrupoActivo ? Colors.white : colorGrupo,
              size: 20,
            ),
          ),
          title: Text(
            'Recetario',
            style: TextStyle(
              fontWeight: esGrupoActivo ? FontWeight.bold : FontWeight.w600,
              color: esGrupoActivo ? colorGrupo : Colors.black87,
              fontSize: 15,
            ),
          ),
          children: [
            _construirSubItem(
              context: context,
              ruta: 'recetas',
              titulo: 'Catálogo Oficial',
              subtitulo: 'Recetas curadas por el chef',
              icono: Icons.star_rounded,
              colorIcono: colorGrupo,
              pantalla: () => const PantallaRecetas(
                filtroInicial: FiltroAudienciaReceta.oficiales,
                rutaMenu: 'recetas',
              ),
            ),
            const SizedBox(height: 2),
            _construirSubItem(
              context: context,
              ruta: 'recetas_mias',
              titulo: 'Mis Creaciones',
              subtitulo: 'Tus recetas y las del Chef IA',
              icono: Icons.person_pin_circle_outlined,
              colorIcono: const Color(0xFF1E2022),
              pantalla: () => const PantallaRecetas(
                filtroInicial: FiltroAudienciaReceta.misRecetas,
                rutaMenu: 'recetas_mias',
              ),
            ),
            const SizedBox(height: 2),
            _construirSubItem(
              context: context,
              ruta: 'caninas',
              titulo: 'Recetas Caninas 🐾',
              subtitulo: 'Nutrición casera para perritos',
              icono: Icons.pets,
              colorIcono: Colors.brown.shade700,
              pantalla: () => const PantallaRecetasCaninas(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirMenuPlaneadorConSubmenu(BuildContext context) {
    final bool esGrupoActivo = rutaActual == 'planeador' || rutaActual == 'calendario';

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: esGrupoActivo ? Colors.teal.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          initiallyExpanded: esGrupoActivo,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          childrenPadding: const EdgeInsets.only(left: 14, right: 8, bottom: 6),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: esGrupoActivo ? Colors.teal : Colors.teal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_month,
              color: esGrupoActivo ? Colors.white : Colors.teal,
              size: 20,
            ),
          ),
          title: Text(
            'Mi Planeador',
            style: TextStyle(
              fontWeight: esGrupoActivo ? FontWeight.bold : FontWeight.w600,
              color: esGrupoActivo ? Colors.teal.shade800 : Colors.black87,
              fontSize: 15,
            ),
          ),
          children: [
            _construirSubItem(
              context: context,
              ruta: 'planeador',
              titulo: 'Planeador por Tiempos',
              subtitulo: 'Desayuno, Comida, Cena',
              icono: Icons.view_list_rounded,
              colorIcono: Colors.teal,
              pantalla: () => const PantallaPlaneador(),
            ),
            const SizedBox(height: 2),
            _construirSubItem(
              context: context,
              ruta: 'calendario',
              titulo: 'Calendario de Comidas',
              subtitulo: 'Vista por días y fechas',
              icono: Icons.calendar_today,
              colorIcono: Colors.teal.shade700,
              badge: 'Nuevo ✨',
              pantalla: () => const PantallaCalendario(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirMenuDespensaYComprasConSubmenu(BuildContext context) {
    final bool esGrupoActivo = rutaActual == 'despensa' ||
        rutaActual == 'carrito' ||
        rutaActual == 'cotizador' ||
        rutaActual == 'hogar';

    const Color colorGrupo = Color(0xFF2E7D32); // Verde Huerto / Despensa Gourmet

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: esGrupoActivo ? colorGrupo.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          initiallyExpanded: esGrupoActivo,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          childrenPadding: const EdgeInsets.only(left: 14, right: 8, bottom: 6),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: esGrupoActivo ? colorGrupo : colorGrupo.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              color: esGrupoActivo ? Colors.white : colorGrupo,
              size: 20,
            ),
          ),
          title: Text(
            'Despensa y Compras',
            style: TextStyle(
              fontWeight: esGrupoActivo ? FontWeight.bold : FontWeight.w600,
              color: esGrupoActivo ? colorGrupo : Colors.black87,
              fontSize: 15,
            ),
          ),
          children: [
            _construirSubItem(
              context: context,
              ruta: 'despensa',
              titulo: 'Mi Despensa',
              subtitulo: 'Insumos, Cava & Refrigerador',
              icono: Icons.kitchen,
              colorIcono: colorGrupo,
              pantalla: () => const PantallaDespensa(),
            ),
            const SizedBox(height: 2),
            _construirSubItem(
              context: context,
              ruta: 'carrito',
              titulo: 'Lista de Compras',
              subtitulo: 'Lista inteligente para el súper',
              icono: Icons.shopping_cart,
              colorIcono: colorGrupo,
              pantalla: () => const PantallaCarrito(),
            ),
            const SizedBox(height: 2),
            _construirSubItem(
              context: context,
              ruta: 'cotizador',
              titulo: 'Cotizador Dinámico',
              subtitulo: 'Compara precios de supermercados',
              icono: Icons.calculate,
              colorIcono: const Color(0xFF455A64),
              pantalla: () => const PantallaCotizador(),
            ),
            const SizedBox(height: 2),
            _construirSubItem(
              context: context,
              ruta: 'hogar',
              titulo: 'Hogar Familiar',
              subtitulo: 'Despensa compartida en casa',
              icono: Icons.family_restroom_rounded,
              colorIcono: const Color(0xFF1976D2),
              badge: 'Familia 👨‍👩‍👧‍👦',
              alPresionar: () {
                Navigator.pop(context);
                ModalHogarFamiliar.mostrar(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirMenuAsistentesIAConSubmenu(BuildContext context) {
    final bool esGrupoActivo = rutaActual == 'chef' || rutaActual == 'sommelier';

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: esGrupoActivo ? Colors.amber.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          initiallyExpanded: esGrupoActivo,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          childrenPadding: const EdgeInsets.only(left: 14, right: 8, bottom: 6),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: esGrupoActivo ? Colors.amber.shade800 : Colors.amber.shade800.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: esGrupoActivo ? Colors.white : Colors.amber.shade800,
              size: 20,
            ),
          ),
          title: Text(
            'Asistentes IA Culinarios',
            style: TextStyle(
              fontWeight: esGrupoActivo ? FontWeight.bold : FontWeight.w600,
              color: esGrupoActivo ? Colors.amber.shade900 : Colors.black87,
              fontSize: 15,
            ),
          ),
          children: [
            _construirSubItem(
              context: context,
              ruta: 'chef',
              titulo: 'Chef IA',
              subtitulo: 'Recetas, Despensa & Robots',
              icono: Icons.soup_kitchen,
              colorIcono: Colors.amber.shade800,
              pantalla: () => const PantallaChef(),
            ),
            const SizedBox(height: 2),
            _construirSubItem(
              context: context,
              ruta: 'sommelier',
              titulo: 'Sommelier IA 🍷',
              subtitulo: 'Cava, Maridaje & Coctelería',
              icono: Icons.wine_bar,
              colorIcono: const Color(0xFF800020),
              badge: 'Nuevo ✨',
              pantalla: () => const PantallaSommelier(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirMenuBienestarYFinanzasConSubmenu(BuildContext context) {
    final bool esGrupoActivo = rutaActual == 'salud' || rutaActual == 'finanzas';
    const Color colorGrupo = Color(0xFF00695C); // Verde Pino / Balance Bienestar

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: esGrupoActivo ? colorGrupo.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          initiallyExpanded: esGrupoActivo,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          childrenPadding: const EdgeInsets.only(left: 14, right: 8, bottom: 6),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: esGrupoActivo ? colorGrupo : colorGrupo.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.health_and_safety_outlined,
              color: esGrupoActivo ? Colors.white : colorGrupo,
              size: 20,
            ),
          ),
          title: Text(
            'Bienestar y Finanzas',
            style: TextStyle(
              fontWeight: esGrupoActivo ? FontWeight.bold : FontWeight.w600,
              color: esGrupoActivo ? colorGrupo : Colors.black87,
              fontSize: 15,
            ),
          ),
          children: [
            _construirSubItem(
              context: context,
              ruta: 'salud',
              titulo: 'Mi Salud',
              subtitulo: 'Calorías, macros e hidratación',
              icono: Icons.favorite,
              colorIcono: Colors.pinkAccent,
              pantalla: () => const PantallaSalud(),
            ),
            const SizedBox(height: 2),
            _construirSubItem(
              context: context,
              ruta: 'finanzas',
              titulo: 'Mis Finanzas',
              subtitulo: 'Presupuesto, gastos y tickets',
              icono: Icons.account_balance_wallet,
              colorIcono: Colors.indigo,
              pantalla: () => const PantallaFinanzas(),
            ),
          ],
        ),
      ),
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
            // Cabecera elegante Bistró Minimalista Dark
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E2022), // Negro Carbón Grafito
                    Color(0xFF2C3437), // Pizarra oscura
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
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
                          color: const Color(0xFFD32F2F), // Sello Rojo Jitomate
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          color: Colors.white,
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
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.search_rounded, color: Colors.deepOrange, size: 20),
                    ),
                    title: const Text(
                      'Búsqueda Spotlight',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 15),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('🔍 Global', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      DialogoBusquedaSpotlight.mostrar(context);
                    },
                  ),
                  _construirMenuRecetasConSubmenu(context),
                  _construirMenuPlaneadorConSubmenu(context),
                  _construirMenuDespensaYComprasConSubmenu(context),
                  _construirMenuAsistentesIAConSubmenu(context),
                  _construirMenuBienestarYFinanzasConSubmenu(context),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Divider(height: 1),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      'AJUSTES Y COMUNIDAD',
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
                    ruta: 'preferencias',
                    titulo: 'Mis Preferencias',
                    icono: Icons.tune,
                    colorIcono: const Color(0xFF455A64),
                    pantalla: () => const PantallaPreferencias(),
                  ),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: Colors.blueAccent, size: 20),
                    ),
                    title: const Text(
                      'Centro de Recordatorios',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 15),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('🔔 Alertas', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ServicioRecordatorios.mostrarModalCentroRecordatorios(context);
                    },
                  ),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.explore_rounded, color: Colors.teal, size: 20),
                    ),
                    title: const Text(
                      'Tour de Bienvenida',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 15),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('🧭 3 Pasos', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      DialogoOnboardingBienvenida.verificarYMostrar(context, forzar: true);
                    },
                  ),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.amber,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Nuestro Manifiesto',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Wellness ✨',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      DialogoManifiestoBienvenida.verificarYMostrar(context, forzar: true);
                    },
                  ),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.install_mobile,
                        color: Color(0xFFD32F2F),
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Instalar en tu Celular',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'PWA 📲',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _mostrarModalInstalacionPwa(context);
                    },
                  ),
                  ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.alternate_email_rounded,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Contacto y Soporte',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: const Text(
                      '@jitomateycebolla.com',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Oficial ✉️',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      DialogoContactoSoporte.mostrar(context);
                    },
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

  void _mostrarModalInstalacionPwa(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.install_mobile,
                      color: Color(0xFFD32F2F),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instalar en tu Celular',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Acceso directo en pantalla completa (Sin tiendas)',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Tarjeta iPhone / Safari
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.apple, color: Colors.black87, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'En iPhone / iPad (Safari)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _construirPasoInstalacion(
                      numero: '1',
                      texto: 'Abre esta página en Safari y toca el botón Compartir (el cuadrito con flecha hacia arriba ⎋).',
                    ),
                    const SizedBox(height: 8),
                    _construirPasoInstalacion(
                      numero: '2',
                      texto: 'Desliza hacia abajo en el menú y selecciona "Agregar a pantalla de inicio" (+).',
                    ),
                    const SizedBox(height: 8),
                    _construirPasoInstalacion(
                      numero: '3',
                      texto: 'Presiona "Agregar" arriba a la derecha. ¡Listo! Ya tienes el icono oficial en tu pantalla.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tarjeta Android / Chrome
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.android, color: Colors.green.shade800, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'En Android (Chrome)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _construirPasoInstalacion(
                      numero: '1',
                      texto: 'Toca los tres puntos (⋮) en la esquina superior derecha de Chrome.',
                    ),
                    const SizedBox(height: 8),
                    _construirPasoInstalacion(
                      numero: '2',
                      texto: 'Selecciona "Instalar aplicación" o "Agregar a la pantalla principal".',
                    ),
                    const SizedBox(height: 8),
                    _construirPasoInstalacion(
                      numero: '3',
                      texto: 'Confirma presionando "Instalar". ¡Se abrirá en pantalla completa como app nativa!',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    '¡Entendido, gracias! 👍',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirPasoInstalacion({required String numero, required String texto}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.orange.shade800,
            shape: BoxShape.circle,
          ),
          child: Text(
            numero,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
          ),
        ),
      ],
    );
  }
}
